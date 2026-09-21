--  PROJEKT IZ MSBP-a — BAZA PODATAKA: FORMULA 1 - Antun Abičić

DROP TABLE IF EXISTS rezultat       CASCADE;
DROP TABLE IF EXISTS kvalifikacije  CASCADE;
DROP TABLE IF EXISTS clan_tima      CASCADE;
DROP TABLE IF EXISTS bolid          CASCADE;
DROP TABLE IF EXISTS vozac          CASCADE;
DROP TABLE IF EXISTS utrka          CASCADE;
DROP TABLE IF EXISTS staza          CASCADE;
DROP TABLE IF EXISTS momcad         CASCADE;


--  1. KREIRANJE TABLICA 

-- Momčad (konstruktor)
CREATE TABLE momcad (
    momcad_id      integer       PRIMARY KEY,
    naziv          varchar(100)  NOT NULL,
    drzava         varchar(60)   NOT NULL,
    god_osnivanja  integer,
    sef_tima       varchar(100),
    sjediste       varchar(100),
    aktivna        boolean       NOT NULL DEFAULT TRUE,
    CONSTRAINT chk_momcad_godina
        CHECK (god_osnivanja BETWEEN 1900 AND EXTRACT(YEAR FROM CURRENT_DATE))
);

-- Vozač (pripada najviše jednoj momčadi -> momcad_id je neobvezan)
CREATE TABLE vozac (
    vozac_id       integer       PRIMARY KEY,
    ime            varchar(50)   NOT NULL,
    prezime        varchar(50)   NOT NULL,
    datum_rodenja  date,
    nacionalnost   varchar(60),
    broj           integer,
    bodovi_ukupno  numeric(6,1)  NOT NULL DEFAULT 0,
    momcad_id      integer       REFERENCES momcad(momcad_id),
    CONSTRAINT chk_vozac_broj   CHECK (broj BETWEEN 1 AND 99),
    CONSTRAINT chk_vozac_bodovi CHECK (bodovi_ukupno >= 0)
);

-- Staza
CREATE TABLE staza (
    staza_id     integer       PRIMARY KEY,
    naziv        varchar(100)  NOT NULL,
    lokacija     varchar(100),
    drzava       varchar(60)   NOT NULL,
    duljina_km   numeric(5,3),
    broj_zavoja  integer,
    CONSTRAINT chk_staza_duljina CHECK (duljina_km > 0),
    CONSTRAINT chk_staza_zavoji  CHECK (broj_zavoja >= 0)
);

-- Utrka (Velika nagrada)
CREATE TABLE utrka (
    utrka_id      integer       PRIMARY KEY,
    naziv         varchar(100)  NOT NULL,
    datum         date          NOT NULL,
    sezona        integer       NOT NULL,
    broj_krugova  integer,
    staza_id      integer       NOT NULL REFERENCES staza(staza_id),
    CONSTRAINT chk_utrka_krugovi CHECK (broj_krugova > 0)
);

-- Bolid
CREATE TABLE bolid (
    bolid_id     integer       PRIMARY KEY,
    naziv_modela varchar(100)  NOT NULL,
    sezona       integer       NOT NULL,
    tip_motora   varchar(60)   NOT NULL,
    momcad_id    integer       NOT NULL REFERENCES momcad(momcad_id)
);

-- Član tima (osoblje momčadi)
CREATE TABLE clan_tima (
    clan_id          integer      PRIMARY KEY,
    ime              varchar(50)  NOT NULL,
    prezime          varchar(50)  NOT NULL,
    uloga            varchar(60)  NOT NULL,
    datum_zaposlenja date         DEFAULT CURRENT_DATE,
    momcad_id        integer      NOT NULL REFERENCES momcad(momcad_id)
);

-- Kvalifikacije (M:N veza vozač - utrka)
CREATE TABLE kvalifikacije (
    kvalifikacije_id integer      PRIMARY KEY,
    vozac_id         integer      NOT NULL REFERENCES vozac(vozac_id),
    utrka_id         integer      NOT NULL REFERENCES utrka(utrka_id),
    q1_vrijeme       numeric(6,3),
    q2_vrijeme       numeric(6,3),
    q3_vrijeme       numeric(6,3),
    startna_pozicija integer,
    CONSTRAINT chk_kval_poz CHECK (startna_pozicija BETWEEN 1 AND 20),
    CONSTRAINT uq_kval      UNIQUE (vozac_id, utrka_id)
);

-- Rezultat (M:N veza vozač - utrka)
CREATE TABLE rezultat (
    rezultat_id  integer       PRIMARY KEY,
    vozac_id     integer       NOT NULL REFERENCES vozac(vozac_id),
    utrka_id     integer       NOT NULL REFERENCES utrka(utrka_id),
    startna_poz  integer,
    zavrsna_poz  integer,
    bodovi       numeric(4,1)  NOT NULL DEFAULT 0,
    status       varchar(30)   NOT NULL DEFAULT 'Završio',
    najbrzi_krug boolean       NOT NULL DEFAULT FALSE,
    CONSTRAINT chk_rez_bodovi CHECK (bodovi >= 0),
    CONSTRAINT chk_rez_status
        CHECK (status IN ('Završio','Odustao','Diskvalificiran','Nije startao')),
    CONSTRAINT uq_rez UNIQUE (vozac_id, utrka_id)
);


--  2. KOMENTARI NA TABLICE I ODABRANE STUPCE
COMMENT ON TABLE momcad        IS 'F1 momčadi (konstruktori) koji nastupaju u prvenstvu';
COMMENT ON TABLE vozac         IS 'Vozači; svaki vozač pripada najviše jednoj momčadi';
COMMENT ON TABLE staza         IS 'Staze na kojima se voze utrke';
COMMENT ON TABLE utrka         IS 'Pojedinačne utrke (Velike nagrade) unutar sezone';
COMMENT ON TABLE bolid         IS 'Bolidi koje momčad koristi u pojedinoj sezoni';
COMMENT ON TABLE clan_tima     IS 'Članovi osoblja momčadi (inženjeri, mehaničari, ...)';
COMMENT ON TABLE kvalifikacije IS 'Rezultati kvalifikacija vozača na pojedinoj utrci (veza M:N)';
COMMENT ON TABLE rezultat      IS 'Rezultati vozača na pojedinoj utrci (veza M:N)';

COMMENT ON COLUMN vozac.bodovi_ukupno IS 'Zbroj bodova iz svih utrka; održava ga okidač trg_azuriraj_bodove';
COMMENT ON COLUMN rezultat.najbrzi_krug IS 'TRUE ako je vozač ostvario najbrži krug na toj utrci';
COMMENT ON COLUMN staza.duljina_km IS 'Duljina kruga u kilometrima';


--  3. INDEKSI 

CREATE INDEX idx_vozac_prezime_ime ON vozac (prezime, ime);

-- Indeksi nad stranim ključevima 
CREATE INDEX idx_vozac_momcad   ON vozac    (momcad_id);
CREATE INDEX idx_utrka_staza    ON utrka    (staza_id);
CREATE INDEX idx_bolid_momcad   ON bolid    (momcad_id);
CREATE INDEX idx_rezultat_vozac ON rezultat (vozac_id);
CREATE INDEX idx_rezultat_utrka ON rezultat (utrka_id);

CREATE INDEX idx_utrka_sezona   ON utrka    (sezona);


--  4. FUNKCIJE

-- 4.1 Broj pobjeda zadanog vozača
CREATE OR REPLACE FUNCTION broj_pobjeda_vozaca(p_vozac_id integer)
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
    v_broj integer;
BEGIN
    SELECT count(*) INTO v_broj
    FROM rezultat
    WHERE vozac_id = p_vozac_id
      AND zavrsna_poz = 1;
    RETURN v_broj;
END;
$$;

-- 4.2 Ukupni bodovi konstruktora 
CREATE OR REPLACE FUNCTION bodovi_momcadi(p_momcad_id integer)
RETURNS numeric
LANGUAGE plpgsql
AS $$
DECLARE
    v_bodovi numeric;
BEGIN
    SELECT COALESCE(sum(r.bodovi), 0) INTO v_bodovi
    FROM rezultat r
    JOIN vozac v ON v.vozac_id = r.vozac_id
    WHERE v.momcad_id = p_momcad_id;
    RETURN v_bodovi;
END;
$$;


--  5. PROCEDURE

-- 5.1 Ponovno izračunati i upisani ukupni bodovi jednog vozača
CREATE OR REPLACE PROCEDURE azuriraj_bodove_vozaca(p_vozac_id integer)
LANGUAGE plpgsql
AS $$
DECLARE
    v_postoji integer;
    v_suma    numeric;
BEGIN
    SELECT count(*) INTO v_postoji FROM vozac WHERE vozac_id = p_vozac_id;
    IF v_postoji = 0 THEN
        RAISE EXCEPTION 'Vozač s id-em % ne postoji.', p_vozac_id;
    END IF;

    SELECT COALESCE(sum(bodovi), 0) INTO v_suma
    FROM rezultat WHERE vozac_id = p_vozac_id;

    UPDATE vozac SET bodovi_ukupno = v_suma WHERE vozac_id = p_vozac_id;
    RAISE NOTICE 'Bodovi vozača % ažurirani na %.', p_vozac_id, v_suma;
END;
$$;

-- 5.2 Dodan rezultat ako ne postoji, inače ga ažuriramo (insert/update)
CREATE OR REPLACE PROCEDURE dodaj_ili_azuriraj_rezultat(
    p_rezultat_id  integer,
    p_vozac_id     integer,
    p_utrka_id     integer,
    p_startna_poz  integer,
    p_zavrsna_poz  integer,
    p_bodovi       numeric,
    p_status       varchar,
    p_najbrzi_krug boolean
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_broj integer;
BEGIN
    SELECT count(*) INTO v_broj
    FROM rezultat
    WHERE vozac_id = p_vozac_id AND utrka_id = p_utrka_id;

    IF v_broj = 0 THEN
        INSERT INTO rezultat(rezultat_id, vozac_id, utrka_id, startna_poz,
                             zavrsna_poz, bodovi, status, najbrzi_krug)
        VALUES (p_rezultat_id, p_vozac_id, p_utrka_id, p_startna_poz,
                p_zavrsna_poz, p_bodovi, p_status, p_najbrzi_krug);
        RAISE NOTICE 'Dodan novi rezultat za vozača % na utrci %.',
                     p_vozac_id, p_utrka_id;
    ELSE
        UPDATE rezultat
        SET startna_poz  = p_startna_poz,
            zavrsna_poz  = p_zavrsna_poz,
            bodovi       = p_bodovi,
            status       = p_status,
            najbrzi_krug = p_najbrzi_krug
        WHERE vozac_id = p_vozac_id AND utrka_id = p_utrka_id;
        RAISE NOTICE 'Ažuriran rezultat za vozača % na utrci %.',
                     p_vozac_id, p_utrka_id;
    END IF;
END;
$$;

-- 5.3 Ispis trenutnog poretka vozača
CREATE OR REPLACE PROCEDURE ispis_poretka_vozaca()
LANGUAGE plpgsql
AS $$
DECLARE
    r        RECORD;
    v_mjesto integer := 0;
BEGIN
    FOR r IN
        SELECT ime, prezime, bodovi_ukupno
        FROM vozac
        ORDER BY bodovi_ukupno DESC, prezime
    LOOP
        v_mjesto := v_mjesto + 1;
        RAISE NOTICE '%. % % — % bodova',
                     v_mjesto, r.ime, r.prezime, r.bodovi_ukupno;
    END LOOP;
END;
$$;


--  6. OKIDAČI

-- 6.1 Održavanje ukupnih bodova vozača nakon promjene u tablici rezultat
CREATE OR REPLACE FUNCTION trg_azuriraj_bodove_fn()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF (TG_OP = 'DELETE') THEN
        UPDATE vozac
        SET bodovi_ukupno =
            (SELECT COALESCE(sum(bodovi),0) FROM rezultat WHERE vozac_id = OLD.vozac_id)
        WHERE vozac_id = OLD.vozac_id;
        RETURN OLD;
    ELSE
        UPDATE vozac
        SET bodovi_ukupno =
            (SELECT COALESCE(sum(bodovi),0) FROM rezultat WHERE vozac_id = NEW.vozac_id)
        WHERE vozac_id = NEW.vozac_id;

        -- ako je rezultat premješten na drugog vozača, osvježi i starog
        IF (TG_OP = 'UPDATE' AND OLD.vozac_id <> NEW.vozac_id) THEN
            UPDATE vozac
            SET bodovi_ukupno =
                (SELECT COALESCE(sum(bodovi),0) FROM rezultat WHERE vozac_id = OLD.vozac_id)
            WHERE vozac_id = OLD.vozac_id;
        END IF;
        RETURN NEW;
    END IF;
END;
$$;

CREATE TRIGGER trg_azuriraj_bodove
AFTER INSERT OR UPDATE OR DELETE ON rezultat
FOR EACH ROW
EXECUTE FUNCTION trg_azuriraj_bodove_fn();

-- 6.2 Provjera ispravnosti kvalifikacijskih vremena
CREATE OR REPLACE FUNCTION trg_provjera_kvalifikacija_fn()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    -- sva unesena vremena moraju biti pozitivna
    IF (NEW.q1_vrijeme IS NOT NULL AND NEW.q1_vrijeme <= 0)
    OR (NEW.q2_vrijeme IS NOT NULL AND NEW.q2_vrijeme <= 0)
    OR (NEW.q3_vrijeme IS NOT NULL AND NEW.q3_vrijeme <= 0) THEN
        RAISE EXCEPTION 'Vrijeme kvalifikacija mora biti pozitivno.';
    END IF;

    -- ne može se imati Q2 vrijeme bez Q1, ni Q3 bez Q2
    IF (NEW.q2_vrijeme IS NOT NULL AND NEW.q1_vrijeme IS NULL) THEN
        RAISE EXCEPTION 'Vozač ne može imati Q2 vrijeme bez Q1 vremena.';
    END IF;
    IF (NEW.q3_vrijeme IS NOT NULL AND NEW.q2_vrijeme IS NULL) THEN
        RAISE EXCEPTION 'Vozač ne može imati Q3 vrijeme bez Q2 vremena.';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_provjera_kvalifikacija
BEFORE INSERT OR UPDATE ON kvalifikacije
FOR EACH ROW
EXECUTE FUNCTION trg_provjera_kvalifikacija_fn();


--  7. UNOS PODATAKA

-- 7.1 Momčadi  
INSERT INTO momcad (momcad_id, naziv, drzava, god_osnivanja, sef_tima, sjediste, aktivna) VALUES
 (1, 'Red Bull Racing', 'Austrija',          2005, 'Christian Horner',   'Milton Keynes', TRUE),
 (2, 'Mercedes',        'Njemačka',          2010, 'Toto Wolff',         'Brackley',      TRUE),
 (3, 'Ferrari',         'Italija',           1929, 'Frédéric Vasseur',   'Maranello',     TRUE),
 (4, 'McLaren',         'Velika Britanija',  1963, 'Andrea Stella',      'Woking',        TRUE),
 (5, 'Aston Martin',    'Velika Britanija',  2021, 'Mike Krack',         'Silverstone',   TRUE),
 (6, 'Williams',        'Velika Britanija',  1977, 'James Vowles',       'Grove',         TRUE),
 (7, 'Alpine',          'Francuska',         2021, 'Bruno Famin',        'Enstone',       TRUE);

INSERT INTO momcad (momcad_id, naziv, drzava, god_osnivanja, sjediste, aktivna) VALUES
 (8, 'Audi F1',         'Njemačka',          2026, 'Hinwil',             FALSE);

-- 7.2 Vozači  (bodovi_ukupno se ne unosi -> zadana 0, okidač ga puni)
INSERT INTO vozac (vozac_id, ime, prezime, datum_rodenja, nacionalnost, broj, momcad_id) VALUES
 ( 1, 'Max',       'Verstappen', DATE '1997-09-30', 'Nizozemska',        1, 1),
 ( 2, 'Sergio',    'Pérez',      DATE '1990-01-26', 'Meksiko',          11, 1),
 ( 3, 'Lewis',     'Hamilton',   DATE '1985-01-07', 'Velika Britanija', 44, 2),
 ( 4, 'George',    'Russell',    DATE '1998-02-15', 'Velika Britanija', 63, 2),
 ( 5, 'Charles',   'Leclerc',    DATE '1997-10-16', 'Monako',           16, 3),
 ( 6, 'Carlos',    'Sainz',      DATE '1994-09-01', 'Španjolska',       55, 3),
 ( 7, 'Lando',     'Norris',     DATE '1999-11-13', 'Velika Britanija',  4, 4),
 ( 8, 'Oscar',     'Piastri',    DATE '2001-04-06', 'Australija',       81, 4),
 ( 9, 'Fernando',  'Alonso',     DATE '1981-07-29', 'Španjolska',       14, 5),
 (10, 'Lance',     'Stroll',     DATE '1998-10-29', 'Kanada',           18, 5),
 (11, 'Alexander', 'Albon',      DATE '1996-03-23', 'Tajland',          23, 6),
 (12, 'Logan',     'Sargeant',   DATE '2000-12-31', 'SAD',               2, 6),
 (13, 'Pierre',    'Gasly',      DATE '1996-02-07', 'Francuska',        10, 7),
 (14, 'Esteban',   'Ocon',       DATE '1996-09-17', 'Francuska',        31, 7),
 -- pričuvni vozač bez momčadi (neobvezni strani ključ je NULL)
 (15, 'Nyck',      'de Vries',   DATE '1995-02-06', 'Nizozemska',       21, NULL);

-- 7.3 Staze  (staza 7 Suzuka nije domaćin nijednoj utrci)
INSERT INTO staza (staza_id, naziv, lokacija, drzava, duljina_km, broj_zavoja) VALUES
 (1, 'Red Bull Ring',                'Spielberg',   'Austrija',         4.318, 10),
 (2, 'Silverstone Circuit',          'Silverstone', 'Velika Britanija', 5.891, 18),
 (3, 'Circuit de Spa-Francorchamps', 'Stavelot',    'Belgija',          7.004, 19),
 (4, 'Autodromo Nazionale Monza',    'Monza',       'Italija',          5.793, 11),
 (5, 'Circuit de Monaco',            'Monte Carlo', 'Monako',           3.337, 19),
 (6, 'Hungaroring',                  'Budimpešta',  'Mađarska',         4.381, 14),
 (7, 'Suzuka Circuit',               'Suzuka',      'Japan',            5.807, 18);

-- 7.4 Utrke
INSERT INTO utrka (utrka_id, naziv, datum, sezona, broj_krugova, staza_id) VALUES
 (1, 'VN Austrije 2023',          DATE '2023-07-02', 2023, 71, 1),
 (2, 'VN Velike Britanije 2023',  DATE '2023-07-09', 2023, 52, 2),
 (3, 'VN Belgije 2023',           DATE '2023-07-30', 2023, 44, 3),
 (4, 'VN Italije 2023',           DATE '2023-09-03', 2023, 53, 4),
 (5, 'VN Austrije 2024',          DATE '2024-06-30', 2024, 71, 1),
 (6, 'VN Velike Britanije 2024',  DATE '2024-07-07', 2024, 52, 2),
 (7, 'VN Monaka 2024',            DATE '2024-05-26', 2024, 78, 5),
 (8, 'VN Mađarske 2024',          DATE '2024-07-21', 2024, 70, 6);

-- 7.5 Bolidi  
INSERT INTO bolid (bolid_id, naziv_modela, sezona, tip_motora, momcad_id) VALUES
 ( 1, 'RB19',  2023, 'Honda RBPT', 1),
 ( 2, 'RB20',  2024, 'Honda RBPT', 1),
 ( 3, 'W14',   2023, 'Mercedes',   2),
 ( 4, 'W15',   2024, 'Mercedes',   2),
 ( 5, 'SF-23', 2023, 'Ferrari',    3),
 ( 6, 'SF-24', 2024, 'Ferrari',    3),
 ( 7, 'MCL60', 2023, 'Mercedes',   4),
 ( 8, 'MCL38', 2024, 'Mercedes',   4),
 ( 9, 'AMR24', 2024, 'Mercedes',   5),
 (10, 'FW46',  2024, 'Mercedes',   6),
 (11, 'A524',  2024, 'Renault',    7);

-- 7.6 Članovi tima  (neki bez datuma -> zadana vrijednost CURRENT_DATE)
INSERT INTO clan_tima (clan_id, ime, prezime, uloga, datum_zaposlenja, momcad_id) VALUES
 (1, 'Pierre', 'Waché',   'Tehnički direktor', DATE '2006-03-01', 1),
 (2, 'Adrian', 'Newey',   'Glavni dizajner',   DATE '2006-02-01', 1),
 (3, 'James',  'Allison', 'Tehnički direktor', DATE '2017-03-01', 2),
 (4, 'Enrico', 'Cardile', 'Tehnički direktor', DATE '2016-05-01', 3),
 (5, 'Rob',    'Marshall', 'Glavni inženjer',  DATE '2024-01-01', 4),
 (6, 'Dan',    'Fallows', 'Tehnički direktor', DATE '2022-04-01', 5);
-- bez datuma zaposlenja (koristi se zadana vrijednost)
INSERT INTO clan_tima (clan_id, ime, prezime, uloga, momcad_id) VALUES
 (7, 'Pat',  'Fry',     'Tehnički direktor', 7),
 (8, 'Loïc', 'Serra',   'Inženjer šasije',   2);

-- 7.7 Kvalifikacije
INSERT INTO kvalifikacije
 (kvalifikacije_id, vozac_id, utrka_id, q1_vrijeme, q2_vrijeme, q3_vrijeme, startna_pozicija) VALUES
 -- VN Austrije 2024 (utrka 5)
 ( 1,  1, 5, 64.500, 64.100, 63.800,  1),
 ( 2,  7, 5, 64.700, 64.200, 63.900,  2),
 ( 3,  8, 5, 64.900, 64.400, 64.100,  3),
 ( 4,  5, 5, 65.000, 64.600, 64.500,  4),
 ( 5,  3, 5, 65.100, 64.800, 64.700,  5),
 ( 6,  4, 5, 65.200, 64.900,   NULL, 12),  -- ispao u Q2
 ( 7, 11, 5, 65.500,   NULL,   NULL, 16),  -- ispao u Q1
 -- VN Velike Britanije 2024 (utrka 6)
 ( 8,  7, 6, 86.000, 85.500, 85.000,  1),
 ( 9,  1, 6, 86.100, 85.600, 85.200,  2),
 (10,  3, 6, 86.200, 85.700, 85.400,  3),
 (11,  4, 6, 86.300, 85.800, 85.500,  4),
 -- VN Austrije 2023 (utrka 1)
 (12,  1, 1, 64.400, 64.000, 63.700,  1),
 (13,  5, 1, 64.800, 64.300, 64.000,  2);

-- 7.8 Rezultati  (okidač automatski ažurira vozac.bodovi_ukupno)
INSERT INTO rezultat
 (rezultat_id, vozac_id, utrka_id, startna_poz, zavrsna_poz, bodovi, status, najbrzi_krug) VALUES
 -- VN Austrije 2023 (utrka 1)
 ( 1,  1, 1, 1, 1, 26, 'Završio', TRUE),
 ( 2,  5, 1, 2, 2, 18, 'Završio', FALSE),
 ( 3,  6, 1, 3, 3, 15, 'Završio', FALSE),
 ( 4,  9, 1, 4, 5, 10, 'Završio', FALSE),
 ( 5,  7, 1, 5, 4, 12, 'Završio', FALSE),
 ( 6,  3, 1, 6, 8,  4, 'Završio', FALSE),
 -- VN Velike Britanije 2023 (utrka 2)
 ( 7,  1, 2, 1, 1, 25, 'Završio', FALSE),
 ( 8,  7, 2, 2, 2, 18, 'Završio', FALSE),
 ( 9,  3, 2, 3, 3, 16, 'Završio', TRUE),
 (10,  5, 2, 4, 4, 12, 'Završio', FALSE),
 (11,  9, 2, 5, 9,  2, 'Završio', FALSE),
 (12,  2, 2, 6, NULL, 0, 'Odustao', FALSE),
 -- VN Belgije 2023 (utrka 3)
 (13,  1, 3, 1, 1, 26, 'Završio', TRUE),
 (14,  2, 3, 2, 2, 18, 'Završio', FALSE),
 (15,  5, 3, 3, 3, 15, 'Završio', FALSE),
 (16,  3, 3, 4, 4, 12, 'Završio', FALSE),
 (17,  9, 3, 5, 5, 10, 'Završio', FALSE),
 -- VN Italije 2023 (utrka 4)
 (18,  1, 4, 1, 1, 25, 'Završio', FALSE),
 (19,  2, 4, 2, 2, 18, 'Završio', FALSE),
 (20,  6, 4, 3, 3, 15, 'Završio', FALSE),
 (21,  5, 4, 4, 4, 12, 'Završio', FALSE),
 (22,  7, 4, 6, NULL, 0, 'Odustao', FALSE),
 -- VN Austrije 2024 (utrka 5)
 (23,  7, 5, 2, 1, 26, 'Završio', TRUE),
 (24,  5, 5, 4, 2, 18, 'Završio', FALSE),
 (25,  6, 5, 5, 3, 15, 'Završio', FALSE),
 (26,  3, 5, 6, 4, 12, 'Završio', FALSE),
 (27,  1, 5, 1, 5, 10, 'Završio', FALSE),
 (28,  8, 5, 3, NULL, 0, 'Odustao', FALSE),
 -- VN Velike Britanije 2024 (utrka 6)
 (29,  1, 6, 2, 1, 25, 'Završio', FALSE),
 (30,  7, 6, 1, 2, 19, 'Završio', TRUE),
 (31,  3, 6, 3, 3, 15, 'Završio', FALSE),
 (32,  4, 6, 4, 4, 12, 'Završio', FALSE),
 (33,  9, 6, 7, 7,  6, 'Završio', FALSE),
 (34, 12, 6, 20, NULL, 0, 'Nije startao', FALSE),
 -- VN Monaka 2024 (utrka 7)
 (35,  5, 7, 1, 1, 25, 'Završio', FALSE),
 (36,  8, 7, 2, 2, 18, 'Završio', FALSE),
 (37,  6, 7, 3, 3, 15, 'Završio', FALSE),
 (38,  7, 7, 4, 4, 12, 'Završio', FALSE),
 (39,  1, 7, 5, 6,  8, 'Završio', FALSE),
 (40, 10, 7, 8, NULL, 0, 'Diskvalificiran', FALSE),
 -- VN Mađarske 2024 (utrka 8)
 (41,  8, 8, 1, 1, 25, 'Završio', FALSE),
 (42,  7, 8, 2, 2, 18, 'Završio', FALSE),
 (43,  3, 8, 3, 3, 16, 'Završio', TRUE),
 (44,  5, 8, 4, 4, 12, 'Završio', FALSE),
 (45,  4, 8, 5, 5, 10, 'Završio', FALSE);



--  7.9 PROŠIRENI PODACI: aktualna postava (sezona 2026) te povijesne
--      momčadi i vozači


-- Audi (preuzeo Sauber) ulazi kao tvornička momčad -> postaje aktivan
UPDATE momcad
SET aktivna = TRUE, naziv = 'Audi', sef_tima = 'Jonathan Wheatley'
WHERE momcad_id = 8;

-- Preostale aktualne momčadi grida za 2026 (grid broji 11 momčadi)
INSERT INTO momcad (momcad_id, naziv, drzava, god_osnivanja, sef_tima, sjediste, aktivna) VALUES
 ( 9, 'Racing Bulls', 'Italija', 2006, 'Alan Permane',  'Faenza',     TRUE),
 (10, 'Haas',         'SAD',     2016, 'Ayao Komatsu',  'Kannapolis', TRUE),
 (11, 'Cadillac',     'SAD',     2026, 'Graeme Lowdon', 'Fishers',    TRUE);

-- Povijesne (ugašene ili preimenovane) momčadi
INSERT INTO momcad (momcad_id, naziv, drzava, god_osnivanja, sjediste, aktivna) VALUES
 (12, 'Toro Rosso',        'Italija',          2006, 'Faenza',      FALSE),
 (13, 'Lotus F1 Team',     'Velika Britanija', 2012, 'Enstone',     FALSE),
 (14, 'Force India',       'Indija',           2008, 'Silverstone', FALSE),
 (15, 'Brawn GP',          'Velika Britanija', 2009, 'Brackley',    FALSE),
 (16, 'Jordan Grand Prix', 'Irska',            1991, 'Silverstone', FALSE),
 (17, 'Toyota F1',         'Japan',            2002, 'Köln',        FALSE),
 (18, 'BMW Sauber',        'Njemačka',         2006, 'Hinwil',      FALSE),
 (19, 'Caterham F1',       'Malezija',         2010, 'Leafield',    FALSE);

-- Premještaji postojećih vozača prema postavi za sezonu 2026
UPDATE vozac SET momcad_id = 11   WHERE vozac_id = 2;   -- Pérez    -> Cadillac
UPDATE vozac SET momcad_id = 3    WHERE vozac_id = 3;   -- Hamilton -> Ferrari
UPDATE vozac SET momcad_id = 6    WHERE vozac_id = 6;   -- Sainz    -> Williams
UPDATE vozac SET momcad_id = 10   WHERE vozac_id = 14;  -- Ocon     -> Haas
UPDATE vozac SET momcad_id = NULL WHERE vozac_id = 12;  -- Sargeant -> više nije u F1

-- Novi aktualni vozači (sezona 2026)
INSERT INTO vozac (vozac_id, ime, prezime, datum_rodenja, nacionalnost, broj, momcad_id) VALUES
 (16, 'Andrea Kimi', 'Antonelli',  DATE '2006-08-25', 'Italija',          12,  2),
 (17, 'Isack',       'Hadjar',     DATE '2004-09-28', 'Francuska',         6,  1),
 (18, 'Liam',        'Lawson',     DATE '2002-02-11', 'Novi Zeland',      30,  9),
 (19, 'Arvid',       'Lindblad',   DATE '2007-08-08', 'Velika Britanija', 41,  9),
 (20, 'Oliver',      'Bearman',    DATE '2005-05-08', 'Velika Britanija', 87, 10),
 (21, 'Nico',        'Hülkenberg', DATE '1987-08-19', 'Njemačka',         27,  8),
 (22, 'Gabriel',     'Bortoleto',  DATE '2004-10-14', 'Brazil',            5,  8),
 (23, 'Franco',      'Colapinto',  DATE '2003-05-27', 'Argentina',        43,  7),
 (24, 'Valtteri',    'Bottas',     DATE '1989-08-28', 'Finska',           77, 11);

-- Povijesni vozači (više ne nastupaju -> bez trenutne momčadi, bez broja)
INSERT INTO vozac (vozac_id, ime, prezime, datum_rodenja, nacionalnost, broj, momcad_id) VALUES
 (25, 'Sebastian', 'Vettel',     DATE '1987-07-03', 'Njemačka',         NULL, NULL),
 (26, 'Kimi',      'Räikkönen',  DATE '1979-10-17', 'Finska',           NULL, NULL),
 (27, 'Michael',   'Schumacher', DATE '1969-01-03', 'Njemačka',         NULL, NULL),
 (28, 'Nico',      'Rosberg',    DATE '1985-06-27', 'Njemačka',         NULL, NULL),
 (29, 'Jenson',    'Button',     DATE '1980-01-19', 'Velika Britanija', NULL, NULL),
 (30, 'Mark',      'Webber',     DATE '1976-08-27', 'Australija',       NULL, NULL),
 (31, 'Felipe',    'Massa',      DATE '1981-04-25', 'Brazil',           NULL, NULL),
 (32, 'Daniel',    'Ricciardo',  DATE '1989-07-01', 'Australija',       NULL, NULL),
 (33, 'Guanyu',    'Zhou',       DATE '1999-05-30', 'Kina',             NULL, NULL),
 (34, 'Kevin',     'Magnussen',  DATE '1992-10-05', 'Danska',           NULL, NULL),
 (35, 'Ayrton',    'Senna',      DATE '1960-03-21', 'Brazil',           NULL, NULL),
 (36, 'Alain',     'Prost',      DATE '1955-02-24', 'Francuska',        NULL, NULL),
 (37, 'Nigel',     'Mansell',    DATE '1953-08-08', 'Velika Britanija', NULL, NULL),
 (38, 'Niki',      'Lauda',      DATE '1949-02-22', 'Austrija',         NULL, NULL);

-- Bolidi za sezonu 2026 (po jedan za svaku aktualnu momčad)
INSERT INTO bolid (bolid_id, naziv_modela, sezona, tip_motora, momcad_id) VALUES
 (12, 'RB22',     2026, 'Red Bull Ford', 1),
 (13, 'W17',      2026, 'Mercedes',      2),
 (14, 'SF-26',    2026, 'Ferrari',       3),
 (15, 'MCL40',    2026, 'Mercedes',      4),
 (16, 'AMR26',    2026, 'Honda',         5),
 (17, 'FW48',     2026, 'Mercedes',      6),
 (18, 'A526',     2026, 'Mercedes',      7),
 (19, 'R26',      2026, 'Audi',          8),
 (20, 'VCARB 03', 2026, 'Red Bull Ford', 9),
 (21, 'VF-26',    2026, 'Ferrari',      10),
 (22, 'C01',      2026, 'Ferrari',      11);

-- Dodatni članovi tima za nove momčadi (neki bez datuma -> zadana vrijednost)
INSERT INTO clan_tima (clan_id, ime, prezime, uloga, datum_zaposlenja, momcad_id) VALUES
 ( 9, 'Ayao',     'Komatsu',  'Direktor momčadi', DATE '2024-01-01', 10),
 (10, 'Jonathan', 'Wheatley', 'Direktor momčadi', DATE '2025-04-01',  8);
INSERT INTO clan_tima (clan_id, ime, prezime, uloga, momcad_id) VALUES
 (11, 'Graeme', 'Lowdon',  'Direktor momčadi', 11),
 (12, 'Alan',   'Permane', 'Direktor momčadi',  9);



--  8. UPITI

--  8.1  JEDNOSTAVNI UPITI 

-- Upit 1: Naziv, država i sjedište svih aktivnih momčadi.
SELECT naziv, drzava, sjediste
FROM momcad
WHERE aktivna = TRUE
ORDER BY naziv;

-- Upit 2: Ime, prezime i broj vozača koji voze s brojem manjim od 30.
SELECT ime, prezime, broj
FROM vozac
WHERE broj < 30
ORDER BY broj;

-- Upit 3: Staze duže od 5 km.
SELECT naziv, drzava, duljina_km
FROM staza
WHERE duljina_km > 5
ORDER BY duljina_km DESC;

-- Upit 4: Sve utrke u sezoni 2024 (naziv i datum).
SELECT naziv, datum
FROM utrka
WHERE sezona = 2024
ORDER BY datum;

-- Upit 5: Bolidi s Mercedesovim motorom.
SELECT naziv_modela, sezona, tip_motora
FROM bolid
WHERE tip_motora = 'Mercedes'
ORDER BY sezona, naziv_modela;


--  8.2  UPITI NAD VIŠE TABLICA

-- Upit 1: Vozači i njihove momčadi.
SELECT v.ime || ' ' || v.prezime AS vozac, m.naziv AS momcad
FROM vozac v
JOIN momcad m ON m.momcad_id = v.momcad_id
ORDER BY m.naziv, v.prezime;

-- Upit 2: Pobjednici svake utrke (vozač, momčad, utrka).
SELECT u.naziv AS utrka,
       v.ime || ' ' || v.prezime AS pobjednik,
       m.naziv AS momcad
FROM rezultat r
JOIN vozac  v ON v.vozac_id  = r.vozac_id
JOIN utrka  u ON u.utrka_id  = r.utrka_id
JOIN momcad m ON m.momcad_id = v.momcad_id
WHERE r.zavrsna_poz = 1
ORDER BY u.datum;

-- Upit 3: Utrke i staze na kojima se voze.
SELECT u.naziv AS utrka, s.naziv AS staza, s.drzava, u.datum
FROM utrka u
JOIN staza s ON s.staza_id = u.staza_id
ORDER BY u.datum;

-- Upit 4: Kvalifikacijski poredak za VN Austrije 2024.
SELECT v.ime || ' ' || v.prezime AS vozac,
       m.naziv AS momcad,
       k.startna_pozicija
FROM kvalifikacije k
JOIN vozac  v ON v.vozac_id  = k.vozac_id
JOIN utrka  u ON u.utrka_id  = k.utrka_id
JOIN momcad m ON m.momcad_id = v.momcad_id
WHERE u.naziv = 'VN Austrije 2024'
ORDER BY k.startna_pozicija;

-- Upit 5: Bodovani rezultati (top 10) sa svim podacima o vozaču i utrci.
SELECT v.prezime AS vozac, u.naziv AS utrka, r.zavrsna_poz, r.bodovi
FROM rezultat r
JOIN vozac v ON v.vozac_id = r.vozac_id
JOIN utrka u ON u.utrka_id = r.utrka_id
WHERE r.bodovi > 0
ORDER BY r.bodovi DESC, u.datum
LIMIT 10;


--  8.3  UPITI S AGREGIRAJUĆIM FUNKCIJAMA

-- Upit 1: Poredak konstruktora (ukupno bodova po momčadi).
SELECT m.naziv AS momcad, SUM(r.bodovi) AS ukupno_bodova
FROM momcad m
JOIN vozac    v ON v.momcad_id = m.momcad_id
JOIN rezultat r ON r.vozac_id  = v.vozac_id
GROUP BY m.naziv
ORDER BY ukupno_bodova DESC;

-- Upit 2: Prosječan broj zavoja staza po državi.
SELECT drzava, ROUND(AVG(broj_zavoja), 1) AS prosjek_zavoja
FROM staza
GROUP BY drzava
ORDER BY prosjek_zavoja DESC;

-- Upit 3: Broj odvoženih utrka po sezoni.
SELECT sezona, COUNT(*) AS broj_utrka
FROM utrka
GROUP BY sezona
ORDER BY sezona;

-- Upit 4: Vozač s najviše osvojenih bodova.
SELECT ime, prezime, bodovi_ukupno
FROM vozac
WHERE bodovi_ukupno = (SELECT MAX(bodovi_ukupno) FROM vozac);

-- Upit 5: Momčadi koje imaju barem dva vozača (broj vozača po momčadi).
SELECT m.naziv AS momcad, COUNT(v.vozac_id) AS broj_vozaca
FROM momcad m
JOIN vozac v ON v.momcad_id = m.momcad_id
GROUP BY m.naziv
HAVING COUNT(v.vozac_id) >= 2
ORDER BY broj_vozaca DESC, m.naziv;


--  8.4  PODUPITI / SKUPOVNE OPERACIJE

-- Upit 1: Vozači s više bodova od prosjeka svih vozača (podupit u WHERE).
SELECT ime, prezime, bodovi_ukupno
FROM vozac
WHERE bodovi_ukupno > (SELECT AVG(bodovi_ukupno) FROM vozac)
ORDER BY bodovi_ukupno DESC;

-- Upit 2: Momčadi koje nemaju nijednog vozača (NOT EXISTS).
SELECT m.naziv, m.drzava
FROM momcad m
WHERE NOT EXISTS (SELECT 1 FROM vozac v WHERE v.momcad_id = m.momcad_id);

-- Upit 3: Vozači koji su barem jednom ostvarili najbrži krug (podupit u IN).
SELECT ime, prezime
FROM vozac
WHERE vozac_id IN (SELECT vozac_id FROM rezultat WHERE najbrzi_krug = TRUE)
ORDER BY prezime;

-- Upit 4: Vozači koji su nastupili i u sezoni 2023 i u sezoni 2024 (INTERSECT).
SELECT v.ime, v.prezime
FROM vozac v JOIN rezultat r ON r.vozac_id = v.vozac_id
            JOIN utrka u ON u.utrka_id = r.utrka_id
WHERE u.sezona = 2023
INTERSECT
SELECT v.ime, v.prezime
FROM vozac v JOIN rezultat r ON r.vozac_id = v.vozac_id
            JOIN utrka u ON u.utrka_id = r.utrka_id
WHERE u.sezona = 2024
ORDER BY prezime;

-- Upit 5: Staze koje nikad nisu bile domaćin utrke (EXCEPT).
SELECT staza_id, naziv FROM staza
EXCEPT
SELECT s.staza_id, s.naziv
FROM staza s JOIN utrka u ON u.staza_id = s.staza_id
ORDER BY staza_id;


--  9. DEMONSTRACIJA PROCEDURA, FUNKCIJA I OKIDAČA

-- Funkcije
SELECT broj_pobjeda_vozaca(1) AS pobjede_verstappen;
SELECT bodovi_momcadi(1)      AS bodovi_red_bull;

-- Procedure
CALL azuriraj_bodove_vozaca(1);
CALL dodaj_ili_azuriraj_rezultat(46, 4, 7, 6, 8, 4, 'Završio', FALSE);
CALL ispis_poretka_vozaca();

-- Okidač 6.2: pokušaj unosa neispravnih kvalifikacija mora pasti.
DO $$
BEGIN
    INSERT INTO kvalifikacije (kvalifikacije_id, vozac_id, utrka_id, q3_vrijeme)
    VALUES (99, 2, 5, 63.5);   -- Q3 bez Q1/Q2
EXCEPTION WHEN others THEN
    RAISE NOTICE 'Okidač je odbio unos: %', SQLERRM;
END;
$$;