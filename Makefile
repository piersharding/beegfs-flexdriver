DOCKER = docker
DOCKERFILE ?= Dockerfile
REGISTRY ?= gitlab.catalyst.net.nz:4567
REGISTRY_NAME=$(REGISTRY)/piers/k8s-hack
DOCKER_USER ?= user
DOCKER_PASSWORD ?= pass
REG_EMAIL ?= user@gitlab.com
KUBE_NAMESPACE ?= default
PULL_SECRET = "gitlab-registry"
IMG ?= csi-beegfs-flexdriver
TAG ?= 00.01
DOCKER_IMAGE ?= $(IMG):$(TAG)
IMAGE_TAG ?= $(REGISTRY_NAME)/$(DOCKER_IMAGE)

BEEGFS_ROOT ?= /mnt/beegfs

CURRENT_DIR = $(shell pwd)
DRIVER_DIR = $(CURRENT_DIR)/tmp/go/src/github.com/kubernetes-csi

# define overides for above variables in here
-include PrivateRules.mak

.PHONY: all 

all: realclean build push

clean:
	rm -f dockerfile/beegfs dockerfile/flexadapter $(DRIVER_DIR)/driver/_output/flexadapter

realclean: clean
	rm -rf $(CURRENT_DIR)/tmp

build_flexadapter:
	if [ ! -d $(DRIVER_DIR)/drivers ]; then \
	mkdir -p $(CURRENT_DIR)/tmp/go/src/github.com/kubernetes-csi && \
	cd $(DRIVER_DIR) && \
	git clone git@github.com:kubernetes-csi/drivers.git; \
	fi; \
	if [ ! -f $(DRIVER_DIR)/drivers/_output/flexadapter ]; then \
	cd $(DRIVER_DIR)/drivers && GOPATH=$(CURRENT_DIR)/tmp/go make flexadapter; \
	fi

build: build_flexadapter
	cp driver/beegfs dockerfile/beegfs
	cp $(DRIVER_DIR)/drivers/_output/flexadapter dockerfile/flexadapter
	cd dockerfile && $(DOCKER) build -t $(DOCKER_IMAGE) -f $(DOCKERFILE) .

push: build
	$(DOCKER) tag $(DOCKER_IMAGE) $(IMAGE_TAG)
	$(DOCKER) push $(IMAGE_TAG)

namespace:
	kubectl describe namespace $(KUBE_NAMESPACE) || kubectl create namespace $(KUBE_NAMESPACE)

regisry-creds: namespace
	kubectl create secret -n $(KUBE_NAMESPACE) \
	  docker-registry $(PULL_SECRET) \
	 --docker-server=$(REGISTRY_NAME) \
	 --docker-username=$(DOCKER_USER) \
	 --docker-password=$(DOCKER_PASSWORD) \
	 --docker-email=$(REG_EMAIL) \
	-o yaml --dry-run | kubectl replace -n $(KUBE_NAMESPACE) --force -f -

launch: regisry-creds
	kubectl apply -f deploy/kubernetes/csi-nodeplugin-rbac.yaml -n $(KUBE_NAMESPACE)
	DOCKER_IMAGE=$(IMAGE_TAG) \
	BEEGFS_ROOT=$(BEEGFS_ROOT) \
	 envsubst < deploy/kubernetes/csi-attacher-beegfs-flexdriver.yaml | kubectl apply -n $(KUBE_NAMESPACE) -f -
	DOCKER_IMAGE=$(IMAGE_TAG) \
	BEEGFS_ROOT=$(BEEGFS_ROOT) \
	 envsubst < deploy/kubernetes/csi-nodeplugin-beegfs-flexdriver.yaml | kubectl apply -n $(KUBE_NAMESPACE) -f -

test:
	kubectl apply -f examples/kubernetes/nginx.yaml -n $(KUBE_NAMESPACE)

curl:
	echo 'Tada!' | sudo tee --append /mnt/beegfs/data/wahoo.txt
	export IP=$$(kubectl get svc www --template='{{.spec.clusterIP}}') && \
	curl http://$${IP}:8000/wahoo.txt

teardown:
	kubectl delete -f examples/kubernetes/nginx.yaml -n $(KUBE_NAMESPACE) || true
	DOCKER_IMAGE=$(IMAGE_TAG) \
	BEEGFS_ROOT=$(BEEGFS_ROOT) \
	 envsubst < deploy/kubernetes/csi-attacher-beegfs-flexdriver.yaml | kubectl delete -n $(KUBE_NAMESPACE) -f - || true
	DOCKER_IMAGE=$(IMAGE_TAG) \
	BEEGFS_ROOT=$(BEEGFS_ROOT) \
	 envsubst < deploy/kubernetes/csi-nodeplugin-beegfs-flexdriver.yaml | kubectl delete -n $(KUBE_NAMESPACE) -f - || true
	kubectl delete -f deploy/kubernetes/csi-nodeplugin-rbac.yaml -n $(KUBE_NAMESPACE) || true
