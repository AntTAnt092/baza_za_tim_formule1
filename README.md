# Baza podataka za Formulu 1

Projektni rad iz kolegija Modeliranje i strukture baza podataka (FMI Osijek, 2026.).
Relacijska baza podataka koja pokriva ključne entitete jedne sezone Formule 1 i
omogućuje upite poput poretka vozača i konstruktora, pregleda pobjednika utrka i
analize kvalifikacijskih rezultata.

Implementirano u **PostgreSQL**.

## Model

MEV model sastoji se od šest entiteta — `MOMCAD`, `VOZAC`, `BOLID`, `CLAN_TIMA`,
`STAZA` i `UTRKA` — te dviju veza više-prema-više (*kvalificira* i *sudjeluje*)
koje povezuju vozače s utrkama. Razrješavanjem tih veza nastaju tablice
`REZULTAT` i `KVALIFIKACIJE`, pa relacijski model ima ukupno osam tablica.

## Sadržaj

- SQL skripta s cjelovitim DDL-om (tablice, zadane vrijednosti, CHECK ograničenja,
  komentari, indeksi), unosom podataka te svih 20 upita
- `Projekt_Formula1_baza_podataka_Antun_Abičić.pdf` — dokumentacija projekta
- MEV i relacijski model (Draw.io)

## Implementirano

**Ograničenja** — strani ključevi, CHECK uvjeti (broj vozača 1–99, startna pozicija
1–20, nenegativni bodovi, ograničen skup statusa rezultata), jedinstven par
(`vozac_id`, `utrka_id`) u tablicama rezultata i kvalifikacija.

**Indeksi** — nad `vozac(prezime, ime)`, svim stranim ključevima koji sudjeluju u
spajanjima te nad `utrka(sezona)`.

**Procedure**
- `azuriraj_bodove_vozaca` — ponovno izračunava ukupne bodove vozača
- `dodaj_ili_azuriraj_rezultat` — insert/update rezultata za par vozač–utrka
- `ispis_poretka_vozaca` — ispisuje trenutni poredak vozača

**Okidači**
- `trg_azuriraj_bodove` — automatski održava `vozac.bodovi_ukupno` nakon svake
  promjene u tablici `rezultat`
- `trg_provjera_kvalifikacija` — provjerava ispravnost vremena Q1–Q3

**Funkcije**
- `broj_pobjeda_vozaca(vozac_id)` — broj pobjeda vozača
- `bodovi_momcadi(momcad_id)` — ukupni bodovi konstruktora

## Pokretanje

```bash
createdb formula1
psql -d formula1 -f <ime_skripte>.sql
```

## Autor

Antun Abičić ([@AntTAnt092](https://github.com/AntTAnt092))
Fakultet primijenjene matematike i informatike u Osijeku, 2026.
