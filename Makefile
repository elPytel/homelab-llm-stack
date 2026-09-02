SHELL := /bin/bash

export CONFIG_PATH ?= $(CURDIR)/config
export TZ ?= Etc/UTC

MODELS := mistral:7b-instruct-q4_K_M zephyr:7b-beta-q4_K_M olmo-3:7b-instruct-q4_K_M mistral:instruct
MODEL_NAME := $(word 1, $(MODELS))
ENV_FILE := .env

SYSTEMD_SERVICE  := ai-stack.service
SYSTEMD_USER_DIR := $(HOME)/.config/systemd/user

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

install:
	@echo "Instaluji závislosti..."
	@./install.sh
	@touch $@

${ENV_FILE}: .env.example
	@echo "Vytvářím $@ soubor..."
	@cp .env.example $@

up: ${ENV_FILE} | $(CONFIG_PATH) install 
	@echo $(MODE_MSG)
	@mkdir -p "$(CONFIG_PATH)/ollama" "$(CONFIG_PATH)/open-webui"
	docker compose --env-file $(ENV_FILE) $(COMPOSE_FILES) up -d
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

test-model:
	@echo "Stahuji a spouštím testovací model Mistral..."
	docker exec -it ollama ollama run $(MODEL_NAME)

user-linger:
	@echo "Povolování user linger pro systemd službu..."
	@loginctl enable-linger $(USER)
	@echo "User linger povolen."

systemd-install: user-linger
	@echo "Instaluji systemd službu..."
	@mkdir -p $(SYSTEMD_USER_DIR)
	@cp ai-stack.service $(SYSTEMD_USER_DIR)/
	@systemctl --user daemon-reload
	@systemctl --user enable ai-stack.service
	@systemctl --user start ai-stack.service
	@echo "Služba nainstalována a spuštěna. Stav služby:"
	@systemctl --user status ai-stack.service

help:
	@echo "Použití:"
	@echo "  make up              - Spustí kontejnery a zajistí modely"
	@echo "  make down            - Zastaví kontejnery"
	@echo "  make logs            - Sleduje logy kontejnerů"
	@echo "  make status          - Zobrazí stav kontejnerů"
	@echo "  make test-model      - Otestuje model Mistral"
	@echo "  make ensure-models   - Zajistí, že všechny modely jsou staženy"
	@echo "  make user-linger     - Povolí user linger pro systemd službu"
	@echo "  make systemd-install - Nainstaluje a spustí systemd službu"
	@echo "  make help            - Zobrazí tuto nápovědu"

clean:
	@echo "Odstraňuji kontejner a konfigurace..."
	docker compose $(COMPOSE_FILES) down -v
	rm -rf $(CONFIG_PATH)