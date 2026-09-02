# Homelab llm stack

Docker files pro spouštění LLM (Large Language Model) stacku v domácím prostředí.

Produční HW: Bazzite VM s passtrough GTX 1070 Ti (8 GB VRAM) a 24 GB RAM.

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

## Modely

### does not support tools
- `mistral:7b-instruct-q4_K_M`: Původní instruktážní verze Mistral v0.1/v0.2 bez formátu pro volání funkcí.
- `zephyr:7b-beta-q4_K_M`: Komunitní fine-tune postavený na původním Mistralu 7B; je laděný na přirozenou konverzaci (DPO), ale formátování pro nástroje v sobě nemá.
- `olmo:7b-instruct-q4_K_M`: FOSS model od Allen Institute zaměřený na transparentnost vah a datasetů; nativní function calling nepodporuje.

### S podporou pro volání funkcí
Podpora pro volání funkcí je dostupná pouze u modelu:
- `mistral:instruct`: Oficiální novější Mistral (v0.3 / NeMo)


Jak se vejde na můj hardware
Na P330 (CPU režim): Spolkne cca 5,5 GB z operační RAM a poběží bez problémů.

Na Bazzite (GTX 1070 Ti – 8 GB VRAM): Pohodlně se vejde celý do 8GB VRAM, přičemž zbydou ještě cca 2,5–3 GB pro kontext a systém.

Pokud bych sáhl po větším bráškovi Mistral NeMo Instruct (12B) (`mistral-nemo:instruct`), ten má cca 7,1 GB. Ten by se na 8GB VRAM dostal na hranu, ale základní 7B `mistral:instruct` je pro 8GB kartu optimální střed.