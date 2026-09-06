SHELL := /bin/bash

CONTAINER_ENGINE := $(shell if command -v docker >/dev/null 2>&1; then echo docker; elif command -v podman >/dev/null 2>&1; then echo podman; fi)
ifeq ($(CONTAINER_ENGINE),podman)
PODMAN_COMPOSE := $(shell if command -v podman-compose >/dev/null 2>&1; then echo podman-compose; elif podman compose version >/dev/null 2>&1; then echo podman compose; fi)
COMPOSE := $(if $(strip $(PODMAN_COMPOSE)),$(PODMAN_COMPOSE),podman-compose)
EXEC := podman exec
else
COMPOSE := docker compose
EXEC := docker exec
endif

export CONFIG_PATH ?= $(CURDIR)/config
export TZ ?= Etc/UTC

MODELS := mistral:7b-instruct-q4_K_M zephyr:7b-beta-q4_K_M olmo-3:7b-instruct-q4_K_M mistral:instruct qwen2.5-coder:7b
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

ip:
	@echo "IP adresa hostitele:" 
	@hostname -I

up: ip ${ENV_FILE} | $(CONFIG_PATH) install
	@echo $(MODE_MSG)
	@mkdir -p "$(CONFIG_PATH)/ollama" "$(CONFIG_PATH)/open-webui"
	$(COMPOSE) --env-file $(ENV_FILE) $(COMPOSE_FILES) up -d
	@$(MAKE) ensure-models

ensure-models:
	@for model in $(MODELS); do \
		if $(EXEC) ollama ollama list 2>/dev/null | grep -q "$$model"; then \
			echo "Model již existuje: $$model"; \
		else \
			echo "Stahuji model: $$model"; \
			$(EXEC) ollama ollama pull "$$model"; \
		fi; \
	done

down:
	$(COMPOSE) $(COMPOSE_FILES) down

logs:
	$(COMPOSE) $(COMPOSE_FILES) logs -f

status:
	$(COMPOSE) $(COMPOSE_FILES) stats --no-stream

test-model:
	@echo "Stahuji a spouštím testovací model Mistral..."
	$(EXEC) -it ollama ollama run $(MODEL_NAME)

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
	$(COMPOSE) $(COMPOSE_FILES) down -v
	rm -rf $(CONFIG_PATH)