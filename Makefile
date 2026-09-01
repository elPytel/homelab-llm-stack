SHELL := /bin/bash

export CONFIG_PATH ?= $(CURDIR)/config
export TZ ?= Etc/UTC

MODELS := mistral:7b-instruct-q4_K_M zephyr:7b-beta-q4_K_M olmo:7b-instruct-q4_K_M mistral:instruct
MODEL_NAME := $(word 1, $(MODELS))

# Detekce NVIDIA GPU na hostiteli
HAS_NVIDIA := $(shell which nvidia-smi 2>/dev/null)

COMPOSE_FILES := -f compose.yml
ifdef HAS_NVIDIA
    COMPOSE_FILES += -f compose.gpu.yml
    MODE_MSG := "NVIDIA GPU detekována -> Spouštím s akcelerací na GPU"
else
    MODE_MSG := "NVIDIA GPU nenalezena -> Spouštím v CPU režimu"
endif

.PHONY: up down logs test-model status ensure-models

all: up

$(CONFIG_PATH):
	@mkdir -p $@

up: | $(CONFIG_PATH)
	@echo $(MODE_MSG)
	@mkdir -p ./config/ollama ./config/open-webui
	docker compose $(COMPOSE_FILES) up -d
	@$(MAKE) ensure-models

ensure-models:
	@for model in $(MODELS); do \
		if docker exec ollama ollama list 2>/dev/null | grep -q "$$model"; then \
			echo "Model již existuje: $$model"; \
		else \
			echo "Stahuji model: $$model"; \
			docker exec ollama ollama pull "$$model"; \
		fi; \
	done

down:
	docker compose $(COMPOSE_FILES) down

logs:
	docker compose $(COMPOSE_FILES) logs -f

status:
	docker compose $(COMPOSE_FILES) stats --no-stream

# Rychlý test otevřeného FOSS modelu
test-model:
	@echo "Stahuji a spouštím testovací model Mistral..."
	docker exec -it ollama ollama run $(MODEL_NAME)

help:
	@echo "Použití:"
	@echo "  make up            - Spustí kontejnery a zajistí modely"
	@echo "  make down          - Zastaví kontejnery"
	@echo "  make logs          - Sleduje logy kontejnerů"
	@echo "  make status        - Zobrazí stav kontejnerů"
	@echo "  make test-model    - Otestuje model Mistral"
	@echo "  make ensure-models - Zajistí, že všechny modely jsou staženy"
	@echo "  make help          - Zobrazí tuto nápovědu"

clean:
	@echo "Odstraňuji kontejner a konfigurace..."
	docker compose $(COMPOSE_FILES) down -v
	rm -rf $(CONFIG_PATH)