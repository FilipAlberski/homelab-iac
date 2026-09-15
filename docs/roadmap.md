# Plan rozwoju homelabu

Lista zadań po przeglądzie repo z 6 września 2026. Opis stanu początkowego
dotyczy konfiguracji i dokumentacji w repo; nie jest potwierdzeniem działania
usług na serwerach. Wszystkie poniższe projekty pozostają do wykonania.

Priorytety i kolejność są propozycją. Nazwy nowych VM są robocze; adresy, VMID,
pojemność dysków i przydział zasobów należy ustalić przed wdrożeniem.

## Kolejność i zależności

| Priorytet | Zadanie | Efekt | Zależności |
|---|---|---|---|
| P1 | Alerty i metryki infrastruktury | Informacja o problemie bez otwierania Grafany | Wybór kanału, dostęp do API/SNMP |
| P1 | Automatyczny backup i test restore | Możliwość odtworzenia danych po awarii | Miejsce na kopie poza hostem |
| P1 | HTTPS | Szyfrowany dostęp do paneli | Wybór nazw i sposobu wydawania certyfikatów |
| P2 | Authentik | Wspólne logowanie do wybranych aplikacji | HTTPS i backup |
| P2 | Immich | Własna biblioteka zdjęć z telefonu | Zapas zasobów, storage, HTTPS i backup |
| P2 | Automatyzacje Home Assistant i Assist | Oświetlenie, powiadomienia i sterowanie głosem | Dostępne urządzenia i backup HA |
| P2 | Powrót Seafile | Synchronizacja i udostępnianie własnych plików | Osobny dysk, HTTPS i backup |
| P3 | Porządki w dokumentacji i utrzymaniu | Łatwiejsze aktualizacje i odtwarzanie labu | Wykonywane przy okazji powyższych prac |

Pierwszy mały etap: uruchomić powiadomienia i wybrać miejsce na backup.
Status kopii w Homepage dodać po uruchomieniu rzeczywistych zadań backupowych.
Następnie domknąć HTTPS. Immich i automatyzacje domu można rozwijać niezależnie
od wdrożenia wspólnego logowania.

## 1. Alerty i metryki infrastruktury

**Po co:** dowiadywać się o niedostępnej usłudze lub kończącym się dysku,
zanim problem zauważą domownicy. Powiadomienie ma wskazywać przyczynę i usługę,
a po naprawie potwierdzać powrót do działania.

**Stan w repo:** Prometheus, Grafana, blackbox_exporter i reguły alertów są
przygotowane. Rola ma teraz opcjonalne połączenie z Alertmanagerem i routing do
Telegrama, ale Alertmanager pozostaje wyłączony do czasu dodania sekretów.
Eksportery Proxmoxa i MikroTika mają flagi wyłączone.

**Postęp implementacji (6 września 2026):** rola `monitoring` ma Alertmanager,
routing Telegrama, grupowanie, opóźnienie krótkich przerw, wiadomości `resolved`
i inhibicję alertów usług po awarii VM. Sekrety są w Vaulta, konfiguracja działa
na `monitor-01`, a syntetyczny alert przeszedł cykl aktywny → ustąpiony.
Pozostaje potwierdzić odbiór obu wiadomości w Telegramie.

**Do zrobienia:**

- [x] Wybrać kanał powiadomień: Telegram. Odbiorca i dane dostępowe są zapisane
      w Ansible Vault.
- [x] Uzupełnić Vault o token bota i chat ID Telegrama, włączyć Alertmanager
      oraz wykonać kontrolowany test alertu i wiadomości `RESOLVED`.
- [x] Rozszerzyć rolę `monitoring` o Alertmanager i połączenie z Prometheusem.
- [x] Ustawić grupowanie powiadomień, opóźnienie dla krótkich przerw i wyciszanie
      alertów usług, gdy znana jest awaria ich VM. Opisać wyciszenie na czas prac.
- [ ] Uruchomić eksportery Proxmoxa i MikroTika z dostępem tylko do odczytu,
      ograniczonym do hosta monitoringu. Zweryfikować dashboardy na realnych danych.
- [ ] Dodać kontrolę dostępności Home Assistant oraz świeżości backupów
      po wykonaniu zadania 2. Sprawdzać brak nowych danych, a nie tylko błąd zadania.
- [ ] Zaplanować kontrolę poza Proxmoxem: zewnętrzny odbiornik okresowego sygnału
      życia, który powiadomi o jego braku. Alertmanager na tym samym hoście nie
      zgłosi całkowitej awarii hosta ani utraty jego łącza.
- [ ] Uzupełnić [instrukcję monitoringu](monitoring.md) o kanał, progi i testy.

**Gotowe, gdy:** kontrolowany alert dochodzi do odbiorcy, naprawa generuje
wiadomość o ustąpieniu problemu, a awaria jednej VM nie powoduje lawiny
powiadomień. Niezależna kontrola wykrywa brak sygnału życia z labu.

**Miejsca zmian:** `ansible/roles/monitoring/`, zmienne monitoringu,
`docs/monitoring.md`.

## 2. Automatyczny backup i test odtworzenia

**Po co:** móc odzyskać dokumenty, konfigurację i VM po utracie dysku lub hosta.
Kopia na tej samej puli `tank-zfs` nie realizuje tego celu.

**Stan w repo:** [plan backupu](backup.md) opisuje zakres i ręczne czynności.
Brakuje opisanej w kodzie automatyzacji harmonogramów i raportowania wyniku.
State Terraform jest lokalny, a jego kopię trzeba wykonać po `apply`.

**Do zrobienia:**

- [x] Wybrać fizycznie osobne miejsce docelowe i sprawdzić jego pojemność.
      Na początek wystarczy backup Proxmoxa na osobny nośnik; przy dodatkowym
      urządzeniu rozważyć Proxmox Backup Server. Kopię najważniejszych danych
      poza domem potraktować jako kolejny etap. 6 września 2026 potwierdzono
      mirror ZFS `tank` z dwóch dysków 3,6 TB oraz osobny dysk 1 TB
      `/mnt/pve/datav1`.
- [x] Wykonać pierwszą ręczną kopię na mirrorze RAID i drugą kopię na osobnym
      dysku 1 TB. Backup z 6 września 2026 obejmuje sześć VM-ów i około 39 GB
      archiwów; dysk filmowy `jelly-01` jest oznaczony `backup=0` i nie został
      skopiowany. Archiwa na obu nośnikach porównano bajt po bajcie.
- [x] Ustalić retencję kopii: dwa backupy dziennie, 14 najnowszych kopii i do
      4 starszych kopii niedzielnych. Automatyzacja usuwa wyłącznie katalogi w
      rozpoznanym formacie `homelab-YYYY-MM-DD-HHMMSS`.
- [x] Skonfigurować harmonogram kopii VM. Zakres obejmuje dyski z `backup=1`,
      a dysk filmowy Jellyfina pozostaje wykluczony przez `backup=0`.
- [x] Dodać rolę Ansible do eksportu Paperless, logicznego dumpu PostgreSQL
      i kopiowania wymaganych danych. Nie kopiować samego działającego `pgdata`
      jako jedynej metody backupu bazy. Eksport działa dwa razy dziennie przed
      backupem VM, zapisuje sumy SHA-256 i raportuje błąd ostatniego przebiegu.
- [ ] Włączyć automatyczne kopie Home Assistant z przesyłaniem poza VM;
      uwzględnić konfigurację Zigbee i dane potrzebne do odzyskania dostępu.
- [ ] Rozszerzyć obsługę `make apply` o zaszyfrowaną kopię state po udanej
      zmianie. Błąd kopiowania ma być widoczny jako osobny błąd backupu;
      nie może powodować automatycznego ponowienia `apply`.
- [ ] Uwzględnić wszystkie używane zaszyfrowane pliki Vault, w tym media
      i monitoring, oraz niezależną kopię hasła. Zachować poza hostem instrukcję
      i klucze potrzebne do odszyfrowania kopii.
- [ ] Opisać ręczny export MikroTika i jego przechowywanie poza routerem.
      Konfiguracja routera i hosta Proxmox nadal pozostaje poza automatyzacją
      repo, zgodnie z obecną architekturą.
- [x] Wystawiać czas ostatniej kompletnej kopii Paperless i wynik kontroli jako
      metryki; alert o braku, niekompletności lub wieku ponad 48 godzin trafia do
      Prometheusa, Homepage i Telegrama. Osobna metryka natychmiast zgłasza
      nieudaną próbę eksportu; data ostatniego testu restore pozostaje osobnym
      zadaniem.
- [x] Odtworzyć testową VM bez interfejsu sieciowego, bez kolizji IP i
      uruchamiania domowych automatyzacji. Test 8 września 2026 potwierdził
      odtworzenie dysku, start Rocky Linux i działanie agenta QEMU.
- [x] Sprawdzić logiczne odtworzenie dumpu Paperless w tymczasowej bazie.
      Test 8 września 2026 zakończył się poprawnie.
- [ ] Potwierdzić odzyskanie realnego dokumentu Paperless po dodaniu pierwszego
      dokumentu do obecnie pustej biblioteki. Powtarzać oba testy co kwartał.

**Gotowe, gdy:** backup działa z harmonogramu, przeterminowana lub nieudana
kopia generuje alert, a odtworzenie z nośnika poza hostem zostało przetestowane.
Samo utworzenie plików kopii nie kończy zadania.

**Miejsca zmian:** nowa rola backupu, `Makefile`, role `monitoring` i `homepage`,
`docs/backup.md`, `docs/rebuild.md`.

## 3. HTTPS dla paneli

**Po co:** szyfrować logowanie i ruch do aplikacji oraz przygotować stabilne
adresy pod Authentik, Immich i Seafile.

**Stan w repo:** Traefik ma port 443 i generuje samopodpisany certyfikat,
ale routery aplikacji wskazują wejście HTTP `web`.

**Do zrobienia:**

- [ ] Wybrać docelowe nazwy: subdomeny własnej zarejestrowanej domeny
      z certyfikatami ACME przez DNS-01 albo lokalne nazwy z własnym urzędem
      certyfikacji i zaufaniem zainstalowanym na urządzeniach. Nie planować
      publicznych certyfikatów Let's Encrypt dla obecnych nazw `*.lab`.
- [ ] Skonfigurować wydawanie i odnawianie certyfikatów w wybranym wariancie.
      Dane API DNS, jeżeli potrzebne, zapisać w Vault z ograniczonymi uprawnieniami.
- [ ] Przełączyć trasy na HTTPS i dodać przekierowanie HTTP.
      Przy zmianie domeny zachować okres przejściowy dla dotychczasowych adresów.
- [ ] Zaktualizować DNS, adresy bazowe aplikacji, zaufane proxy, dashboardy
      i cele monitoringu. Sprawdzić przesyłanie plików i połączenia WebSocket.
- [ ] Sprawdzić używane bezpośrednio panele, np. Pi-hole i Home Assistant,
      żeby objąć je planem migracji, a nie tylko istniejące trasy Traefika.
- [ ] Ograniczyć bezpośredni dostęp do panelu administracyjnego Traefika
      i sprawdzić, które porty aplikacji muszą pozostać dostępne w LAN.
- [ ] Przetestować odnowienie certyfikatu i alert przed jego wygaśnięciem.

**Gotowe, gdy:** przeglądarka i używane aplikacje mobilne ufają certyfikatom,
logowanie oraz upload działają po HTTPS, a odnawianie nie wymaga ręcznej wymiany
plików. Samo HTTPS nie oznacza publikacji usług w internecie.

**Miejsca zmian:** role `proxy`, `pihole`, konfiguracje aplikacji i monitoringu,
`docs/network.md`.

## 4. Authentik — wspólne logowanie

**Po co:** zarządzać dostępem domowników do wybranych aplikacji z jednego miejsca.

**Do zrobienia:**

- [ ] Po wdrożeniu HTTPS wybrać miejsce dla usługi, przydział zasobów i backup
      bazy oraz konfiguracji. Dodać osobną rolę Ansible i Compose.
- [ ] Przygotować konta i grupy, np. administratorzy oraz domownicy.
      Zachować lokalne konta awaryjne w ważnych aplikacjach.
- [ ] Dla każdej aplikacji ustalić obsługiwany mechanizm: natywne OIDC,
      inna wspierana integracja albo `forwardAuth` przed panelem.
      Bramka logowania nie zawsze zastępuje konto wewnątrz aplikacji.
- [ ] Zacząć od jednej aplikacji, sprawdzić logowanie, wylogowanie i odebranie
      dostępu, a następnie dołączać kolejne.
- [ ] Ograniczyć dostęp do backendów tak, aby chronionego panelu nie można
      było otworzyć z pominięciem proxy przez bezpośredni port.
- [ ] Osobno sprawdzić klientów Jellyfina na TV i telefonie, API oraz integracje
      między aplikacjami. Nie obejmować ich zbiorczo przekierowaniem do logowania.
- [ ] Przetestować dostęp awaryjny podczas zatrzymania Authentika.

**Gotowe, gdy:** wybrane panele korzystają ze wspólnego logowania, uprawnienia
domowników są sprawdzone, a awaria Authentika nie blokuje administracji labem.

**Miejsca zmian:** nowa rola `authentik`, role `proxy` i obsługiwanych aplikacji,
dokumentacja dostępu i odtwarzania.

## 5. Immich — zdjęcia i filmy z telefonu

**Po co:** przechowywać i przeglądać prywatną bibliotekę zdjęć na własnym serwerze,
z automatycznym przesyłaniem z telefonów domowników.

**Do zrobienia:**

- [ ] Sprawdzić wolny RAM, CPU i miejsce na Proxmoxie oraz wielkość biblioteki.
      Punkt wyjścia według dokumentacji sprawdzonej 6 września 2026 to 4 vCPU
      i 8 GB RAM; ponownie sprawdzić wymagania przy wyborze wersji.
- [ ] Dodać roboczą VM `photos-01` z osobnym dyskiem danych na `tank-zfs`.
      Rozmiar uwzględnia oryginały, miniatury, przetworzone filmy i wzrost biblioteki.
- [ ] Dodać rolę `immich` opartą na oficjalnym Compose wybranej wersji,
      sekrety w Vault i kontrolowane wersje obrazów. Dopasować `app_storage`
      do wymagań aplikacji i zatrzymywać start przy braku właściwego mountu.
- [ ] Dodać DNS, HTTPS, skrót w Homepage i kontrolę dostępności.
- [ ] Skonfigurować konta i przetestować upload małego albumu z telefonu,
      odtwarzanie wideo oraz pobranie oryginału.
- [ ] Wykonać backup bazy i plików zdjęć oraz próbę restore przed masowym importem.
      Automatyczne przesyłanie z telefonu nie zastępuje kopii serwera.
- [ ] Opisać aktualizację, kontrolę miejsca i postępowanie po nieudanej migracji.
      Nie zakładać, że cofnięcie obrazu kontenera odwróci migrację bazy.

**Gotowe, gdy:** zdjęcia z telefonu trafiają na serwer, są dostępne w aplikacji
i WWW, a przykładowy album wraz z metadanymi można odzyskać z backupu.

**Miejsca zmian:** Terraform VM, inventory, nowa rola `immich`, role `proxy`,
`pihole`, `homepage` i `monitoring`, osobna instrukcja obsługi zdjęć.

## 6. Home Assistant — automatyzacje i głos

**Po co:** wykorzystać istniejące HAOS i koordynator SMLIGHT do codziennych
czynności. Dobór scenariuszy zależy od posiadanych czujników i urządzeń.

**Do zrobienia:**

- [ ] Spisać urządzenia, pomieszczenia i nazwy encji. Utrzymać istniejące ZHA;
      zmiana integracji Zigbee nie jest potrzebna do tych scenariuszy.
- [ ] Dodać nocne światło po wykryciu ruchu: niska jasność, określone godziny,
      wyłączenie po czasie i możliwość ręcznego sterowania.
- [ ] Dodać informację o zakończeniu prania na podstawie pomiaru mocy przez
      odpowiednie urządzenie: najpierw wykrycie pracy, potem utrzymujący się spadek,
      aby krótkie pauzy programu nie powodowały fałszywych powiadomień.
- [ ] Dodać pomiar energii homelabu po zapewnieniu urządzenia pomiarowego.
      Pokazywać zużycie dobowe i koszt według ustawionej taryfy;
      nie wyliczać poboru energii wyłącznie z procentowego użycia CPU.
- [ ] Uruchomić pilotaż Assist z telefonu: kilka poleceń dla świateł i scen.
      Sprawdzić język polski, czas odpowiedzi i obciążenie lokalnego przetwarzania,
      zanim zostaną wybrane dodatkowe urządzenia głosowe.
- [ ] Zapisać automatyzacje lub instrukcję ich odtworzenia w repo bez sekretów,
      a stan integracji i parowania zabezpieczyć backupem Home Assistant.

**Gotowe, gdy:** wybrane scenariusze działają przez tydzień bez fałszywych
powiadomień i dają się ręcznie wyłączyć. Osobno odnotować wynik pilotażu głosu.
Aktualizacje działającego HAOS nadal wykonywać z jego panelu, zgodnie
z [obecną instrukcją](home-assistant.md).

## 7. Seafile — powrót synchronizacji plików

**Po co:** odtworzyć planowaną usługę synchronizacji dokumentów i innych plików
między komputerami. To osobny projekt od biblioteki zdjęć Immich.

**Do zrobienia:**

- [ ] Potwierdzić potrzebę, zakres danych i wymagania według istniejących
      [notatek wdrożenia Seafile](seafile-rebuild-notes.md).
- [ ] Przygotować VM `files-01` z osobnym dyskiem danych i nową rolę Ansible.
      Nie współdzielić filesystemu aplikacji z Paperless.
- [ ] Wybrać wspieraną wersję i edycję, wygenerować nowe sekrety i skonfigurować
      HTTPS od pierwszego uruchomienia.
- [ ] Przetestować synchronizację między dwoma klientami oraz odzyskanie
      pliku i biblioteki z backupu bazy i danych.
- [ ] Integrację z Authentikiem wykonać dopiero po sprawdzeniu możliwości
      wybranej edycji; zachować lokalnego administratora awaryjnego.

**Gotowe, gdy:** synchronizacja i odtworzenie działają, a sposób utrzymania
jest opisany. Szczegóły wdrożenia aktualizować w istniejących notatkach Seafile.

## 8. Porządki przy okazji wdrożeń

- [ ] Uzgodnić `docs/monitoring.md` i komentarze w zmiennych z faktem, że
      `deploy_metrics_agents` oraz `deploy_monitoring` mają wartość `true`.
      Oddzielać informację o konfiguracji od daty weryfikacji na serwerze.
- [ ] Przy przeglądzie aktualizacji zastąpić `nagios_image: ...:latest`
      zweryfikowaną wersją lub digestem i opisać sposób aktualizowania obrazów.
- [ ] Domknąć istniejące [zadania media stacku](media-stack-todo.md), zwłaszcza
      kontrolowany test odcięcia VPN oraz rzeczywistego transkodowania.
      Wyniki i daty zapisywać tam, bez powielania drugiej checklisty.
- [ ] Po każdym etapie sprawdzić odpowiednie konfiguracje i zachowanie usługi,
      w tym ponowne uruchomienie playbooka, oraz zaktualizować instrukcję rebuilda.
- [ ] Zamykając zadanie w tym dokumencie, dopisać datę, wynik testu i odnośnik
      do instrukcji obsługi. Samo dodanie roli nie oznacza ukończenia wdrożenia.

Pozostają w mocy granice z [architektury](architecture.md): pojedynczy host,
Terraform dla VM i Ansible dla usług. Ten plan nie wymaga Kubernetes, zmiany
backendu state, automatycznego CI ani przebudowy MikroTika. `dataV1` pozostaje
poza zakresem prac.

## Dokumentacja rozwiązań

Źródła sprawdzone przy przygotowaniu propozycji 6 września 2026.
Wersje i szczegóły integracji zweryfikować ponownie przed wdrożeniem.

- [Alertmanager — grupowanie i routing powiadomień](https://prometheus.io/docs/alerting/latest/alertmanager/)
- [Alertmanager — konfiguracja Telegrama](https://prometheus.io/docs/alerting/latest/configuration/#telegram_config)
- [Proxmox Backup Server](https://pbs.proxmox.com/docs/introduction.html)
- [Traefik — certyfikaty ACME](https://doc.traefik.io/traefik/reference/install-configuration/tls/certificate-resolvers/acme/)
- [Authentik — proxy i forward auth](https://docs.goauthentik.io/add-secure-apps/providers/proxy/)
- [Immich — pierwsze uruchomienie](https://docs.immich.app/overview/quick-start/)
- [Immich — wymagania](https://docs.immich.app/install/requirements/)
- [Home Assistant Assist](https://www.home-assistant.io/voice_control/)
