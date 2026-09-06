# Homelab llm stack

- [Homelab llm stack](#homelab-llm-stack)
  - [Architektura](#architektura)
  - [WebUI](#webui)
  - [Instalace](#instalace)
  - [Modely](#modely)
    - [Bez podpory pro volání funkcí](#bez-podpory-pro-volání-funkcí)
    - [S podporou pro volání funkcí](#s-podporou-pro-volání-funkcí)
  - [Automatické spouštění](#automatické-spouštění)
    - [Kontrola stavu a diagnostika](#kontrola-stavu-a-diagnostika)
  - [Přidání dalších uživatelů](#přidání-dalších-uživatelů)
    - [Povolení modelů pro běžné uživatele (Globální nastavení)](#povolení-modelů-pro-běžné-uživatele-globální-nastavení)


Docker files pro spouštění LLM (Large Language Model) stacku v domácím prostředí.

Produční HW: Bazzite VM s passtrough GTX 1070 Ti (8 GB VRAM) a 16 GB RAM.

Testovací HW: P330 i5-8500T s 24 GB RAM (CPU režim).

## Architektura
Jako backend pro modely jsme vybrali kombinaci **Ollama (backend) + Open WebUI (frontend)**:

```txt
┌────────────────────────────────────────────────────────┐
│  Bazzite VM (s passthrough GTX 1070 Ti)                │
│                                                        │
│  ┌──────────────────────┐    ┌──────────────────────┐  │
│  │ Sunshine / Steam     │    │ Ollama (Docker/Podman│  │
│  │ (aktivní při hraní)  │    │ kontejner s GPU)     │  │
│  └──────────────────────┘    └──────────▲───────────┘  │
│                                         │ API: 11434   │
│                              ┌──────────┴───────────┐  │
│                              │ Open WebUI           │  │
│                              │ (web pro síť :3000)  │  │
│                              └──────────────────────┘  │
└────────────────────────────────────────────────────────┘
```

## WebUI

WebUI je dostupné na adrese: [http://localhost:3000](http://localhost:3000)

Nebo na adrese stroje v lokální síti kde je stack spuštěný.

## Instalace

Instalaci a první spuštění provede Makefile jediným příkazem:

```bash
make
```

Příkaz postupně:

1. Spustí `install.sh`, který podle distribuce nainstaluje potřebné závislosti:
  - Debian/Ubuntu: Docker, Docker Compose plugin, Make a cURL.
  - Bazzite/Fedora: Podman a `podman-compose` pomocí `rpm-ostree`, pokud chybí.
2. Vytvoří `.env` z `.env.example` a připraví adresáře `config/ollama/` a `config/open-webui/`.
3. Zkontroluje dostupnost NVIDIA GPU pomocí `nvidia-smi`. Pokud je GPU dostupná, přidá `compose.gpu.yml` a spustí Ollamu s GPU akcelerací.
4. Stáhne image `docker.io/ollama/ollama:latest` a `ghcr.io/open-webui/open-webui:latest` a spustí kontejnery na pozadí.
5. V kontejneru Ollama ověří a případně stáhne modely uvedené v Makefile.

Na Bazzite může instalace Podmanu nebo `podman-compose` vyžadovat restart systému. Po restartu spusť instalaci znovu:

```bash
make
```

Po úspěšném dokončení je WebUI dostupné na [http://localhost:3000](http://localhost:3000). První spuštění může trvat déle kvůli stažení image a modelů.

> [!tip]
> Chvíli to může trvat než poprvé WebUI naběhne, dejte mu čas (pár minut).

## Modely

### Bez podpory pro volání funkcí

Ve webUI vám vyhodít chybu: `does not support tools`.

- `mistral:7b-instruct-q4_K_M`: Původní instruktážní verze Mistral v0.1/v0.2 bez formátu pro volání funkcí.
- `zephyr:7b-beta-q4_K_M`: Komunitní fine-tune postavený na původním Mistralu 7B; je laděný na přirozenou konverzaci (DPO), ale formátování pro nástroje v sobě nemá.

### S podporou pro volání funkcí
Podpora pro volání funkcí je dostupná pouze u modelu:
- `mistral:instruct`: Oficiální novější Mistral (v0.3 / NeMo)
- `olmo-3:7b-instruct-q4_K_M`: FOSS model od Allen Institute zaměřený na transparentnost vah a datasetů.

Jak se vejde na můj hardware:
- Na P330 (CPU režim): Spolkne cca 5,5 GB z operační RAM a běží bez problémů.
- Na Bazzite (GTX 1070 Ti – 8 GB VRAM): Pohodlně se vejde celý do 8GB VRAM, přičemž zbydou ještě cca 2,5–3 GB pro kontext a systém.

Pokud bych sáhl po větším bráškovi Mistral NeMo Instruct (12B) (`mistral-nemo:instruct`), ten má cca 7,5 GB. Ten by se na 8GB VRAM dostal na hranu, ale základní 7B `mistral:instruct` je pro 8GB kartu optimální střed.

## Automatické spouštění

V Bazzite (který je postavený na atomické Fedoře s immutable kořenem) je standardem pro orchestraci kontejnerů bez root práv **systemd user service** s **Podmanem** nebo **Docker Compose**.

Nejčistší a nejspolehlivější sysadmin cesta pro Bazzite je vytvořit systemd unitu pod vaším uživatelem. Ta zajistí, že se stack nastartuje ihned po bootu virtuálky.

Tento příkaz vytvoří systemd unitu a rovnou ji nastartuje:

```bash
make systemd-install
```

> [!tip]
> Součástí je automatická kontrola změn v repu a `git pull`. 

### Kontrola stavu a diagnostika

Zda se stack správně zavedl a jaké má logy, zkontrolujete standardními příkazy:

```bash
# Stav služby
systemctl --user status ai-stack.service

# Sledování logů při bootu
journalctl --user -u ai-stack.service -f
```

Při každém dalším startu Bazzite systemd automaticky zavolá `make up`, Makefile detekuje přítomnost NVIDIA karty a Ollama s WebUI okamžitě naběhnou s GPU akcelerací.

## Přidání dalších uživatelů

### Povolení modelů pro běžné uživatele (Globální nastavení)

1. Přihlaste se do Open WebUI pod svým Admin účtem.
2. Vlevo dole klikni na svůj Profil -> Administrátorský panel (Admin Panel).
3. Přejděte do záložky Nastavení (Settings) -> Modely (Models).
4. Zkontroluj nastavení Viditelnost modelů (Model Visibility).